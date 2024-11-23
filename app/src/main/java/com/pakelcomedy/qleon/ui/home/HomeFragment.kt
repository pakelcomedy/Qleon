package com.pakelcomedy.qleon.ui.home

import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.navigation.fragment.findNavController
import androidx.viewpager2.widget.ViewPager2
import com.pakelcomedy.qleon.R
import com.pakelcomedy.qleon.databinding.FragmentHomeBinding

class HomeFragment : Fragment(R.layout.fragment_home) {

    private var _binding: FragmentHomeBinding? = null
    private val binding get() = _binding!!

    private val viewModel: HomeViewModel by viewModels()

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentHomeBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Debugging NavController current destination (can be removed once issues are resolved)
        val currentDestination = findNavController().currentDestination?.id
        Log.d("NavigationDebug", "Current Destination: $currentDestination")

        // Initialize ViewPager with HomeViewPagerAdapter
        val adapter = HomeViewPagerAdapter(this)
        binding.viewPager.adapter = adapter

        // Restore selected tab from ViewModel
        binding.viewPager.currentItem = viewModel.selectedTabIndex
        updateTabUI(viewModel.selectedTabIndex)

        // Listen for ViewPager page changes
        binding.viewPager.registerOnPageChangeCallback(object : ViewPager2.OnPageChangeCallback() {
            override fun onPageSelected(position: Int) {
                super.onPageSelected(position)
                viewModel.selectedTabIndex = position
                updateTabUI(position)
            }
        })

        // Tab click listeners for navigation
        binding.chatsText.setOnClickListener {
            // Navigate to Home Chat
            findNavController().navigate(R.id.action_homeFragment_to_homeChatFragment)
        }

        binding.newChatText.setOnClickListener {
            // Navigate to New Chat Fragment
            findNavController().navigate(R.id.action_homeFragment_to_newChatFragment)
        }
    }

    private fun updateTabUI(position: Int) {
        // Update tab UI to highlight the selected tab
        val isChatSelected = position == 0
        binding.chatsText.setTextColor(
            ContextCompat.getColor(
                requireContext(),
                if (isChatSelected) R.color.white else R.color.gray
            )
        )
        binding.newChatText.setTextColor(
            ContextCompat.getColor(
                requireContext(),
                if (isChatSelected) R.color.gray else R.color.white
            )
        )
        binding.chatsUnderline.visibility = if (isChatSelected) View.VISIBLE else View.GONE
        binding.newChatUnderline.visibility = if (isChatSelected) View.GONE else View.VISIBLE
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}