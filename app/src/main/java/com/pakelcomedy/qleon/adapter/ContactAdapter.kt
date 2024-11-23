package com.pakelcomedy.qleon.adapter

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.pakelcomedy.qleon.databinding.ItemContactBinding
import com.pakelcomedy.qleon.model.Contact

class ContactAdapter(
    private var contactList: List<Contact>,
    private val onItemClick: (Contact) -> Unit
) : RecyclerView.Adapter<ContactAdapter.ContactViewHolder>() {

    // Update contact list when data changes
    fun updateContacts(newContactList: List<Contact>) {
        contactList = newContactList
        notifyDataSetChanged()  // Notify adapter of data change
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ContactViewHolder {
        val binding = ItemContactBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return ContactViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ContactViewHolder, position: Int) {
        holder.bind(contactList[position])
    }

    override fun getItemCount(): Int = contactList.size

    inner class ContactViewHolder(private val binding: ItemContactBinding) : RecyclerView.ViewHolder(binding.root) {
        fun bind(contact: Contact) {
            binding.contactName.text = contact.name
            binding.contactLastMessage.text = contact.lastMessage
            binding.root.setOnClickListener { onItemClick(contact) }
        }
    }
}