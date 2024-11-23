package com.pakelcomedy.qleon.ui.home

import androidx.fragment.app.FragmentActivity
import androidx.viewpager2.adapter.FragmentStateAdapter
import com.pakelcomedy.qleon.ui.homechat.HomeChatFragment
import com.pakelcomedy.qleon.ui.newchat.NewChatFragment

class HomeViewPagerAdapter(activity: FragmentActivity) : FragmentStateAdapter(activity) {

    override fun getItemCount(): Int = 2  // Chats and New Chat tabs

    override fun createFragment(position: Int) = when (position) {
        0 -> HomeChatFragment() // Display HomeChatFragment in "Chats" tab
        1 -> NewChatFragment() // Display NewChatFragment in "New Chat" tab
        else -> throw IllegalStateException("Unexpected position $position")
    }
}